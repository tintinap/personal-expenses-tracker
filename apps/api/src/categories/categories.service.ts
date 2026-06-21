import { Injectable, ConflictException, NotFoundException } from '@nestjs/common';
import { CategoriesRepository } from './categories.repository';
import { CreateCategoryDto, UpdateCategoryDto } from './categories.model';
import { Category } from '@prisma/client';

@Injectable()
export class CategoriesService {
  constructor(private readonly repository: CategoriesRepository) {}

  async findAll(userId: string): Promise<Category[]> {
    return this.repository.findAll(userId);
  }

  async findById(id: string, userId: string): Promise<Category> {
    const category = await this.repository.findById(id, userId);
    if (!category) {
      throw new NotFoundException(`Category not found`);
    }
    return category;
  }

  async create(userId: string, data: CreateCategoryDto): Promise<Category> {
    if (data.parentId) {
      const parent = await this.findById(data.parentId, userId);
      if (parent.parentId) {
        throw new ConflictException('Nested categories are limited to 1 level depth');
      }
    }

    const maxSortOrder = await this.repository.getMaxSortOrder(userId);
    
    return this.repository.create({
      userId,
      name: data.name,
      colourHex: data.colourHex,
      parentId: data.parentId,
      iconCodePoint: data.iconCodePoint,
      isDefault: false,
      sortOrder: (maxSortOrder ?? -1) + 1,
    });
  }

  async update(
    id: string,
    userId: string,
    data: UpdateCategoryDto,
  ): Promise<Category> {
    if (data.parentId) {
      const parent = await this.findById(data.parentId, userId);
      if (parent.parentId) {
        throw new ConflictException('Nested categories are limited to 1 level depth');
      }
    }
    return this.repository.update(id, userId, data);
  }

  async remove(id: string, userId: string): Promise<void> {
    const count = await this.repository.countAssociatedExpenses(id, userId);

    if (count > 0) {
      throw new ConflictException(
        `Category has ${count} associated expenses. Reassign them before deleting.`,
      );
    }

    await this.repository.delete(id, userId);
  }
}
