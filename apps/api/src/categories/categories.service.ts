import { Injectable, ConflictException } from '@nestjs/common';
import { CategoriesRepository } from './categories.repository';
import { CreateCategoryDto, UpdateCategoryDto } from './categories.model';
import { Category } from '@prisma/client';

@Injectable()
export class CategoriesService {
  constructor(private readonly repository: CategoriesRepository) {}

  async findAll(userId: string): Promise<Category[]> {
    return this.repository.findAll(userId);
  }

  async create(userId: string, data: CreateCategoryDto): Promise<Category> {
    const maxSortOrder = await this.repository.getMaxSortOrder(userId);
    
    return this.repository.create({
      userId,
      name: data.name,
      colourHex: data.colourHex,
      isDefault: false,
      sortOrder: (maxSortOrder ?? -1) + 1,
    });
  }

  async update(
    id: string,
    userId: string,
    data: UpdateCategoryDto,
  ): Promise<Category> {
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
