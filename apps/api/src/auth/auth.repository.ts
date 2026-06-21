import { Injectable } from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';
import { Prisma, User } from '@prisma/client';

@Injectable()
export class AuthRepository {
  constructor(private readonly prisma: PrismaService) {}

  async findUserByProvider(authProvider: string, providerId: string): Promise<User | null> {
    return this.prisma.user.findFirst({
      where: {
        authProvider,
        providerId,
      },
    });
  }

  async createUser(data: Prisma.UserCreateInput): Promise<User> {
    return this.prisma.user.create({
      data,
    });
  }

  async updateUser(id: string, data: Prisma.UserUpdateInput): Promise<User> {
    return this.prisma.user.update({
      where: { id },
      data,
    });
  }

  async findUserById(id: string): Promise<User | null> {
    return this.prisma.user.findUnique({
      where: { id },
    });
  }

  async deleteUser(id: string): Promise<User> {
    return this.prisma.user.delete({
      where: { id },
    });
  }

  async seedDefaultCategories(userId: string): Promise<void> {
    const defaults = [
      { name: 'Food & dining', colourHex: '#378ADD', sortOrder: 0 },
      { name: 'Groceries', colourHex: '#4CAF50', sortOrder: 1 },
      { name: 'Transport', colourHex: '#FF7043', sortOrder: 2 },
      { name: 'Health & medical', colourHex: '#E91E8C', sortOrder: 3 },
      { name: 'Shopping & retail', colourHex: '#9C27B0', sortOrder: 4 },
      { name: 'Bills & utilities', colourHex: '#009688', sortOrder: 5 },
      { name: 'Entertainment', colourHex: '#FFC107', sortOrder: 6 },
      { name: 'Travel', colourHex: '#FF8F00', sortOrder: 7 },
      { name: 'Subscriptions', colourHex: '#F44336', sortOrder: 8 },
      { name: 'Education', colourHex: '#455A64', sortOrder: 9 },
      { name: 'Personal care', colourHex: '#4FC3F7', sortOrder: 10 },
      { name: 'Other / uncategorised', colourHex: '#9E9E9E', sortOrder: 11 },
    ];

    await this.prisma.category.createMany({
      data: defaults.map((cat) => ({
        userId,
        name: cat.name,
        colourHex: cat.colourHex,
        isDefault: true,
        sortOrder: cat.sortOrder,
      })),
    });
  }
}
