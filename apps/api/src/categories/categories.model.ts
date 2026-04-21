export class CreateCategoryDto {
  name: string;
  colourHex: string;
}

export class UpdateCategoryDto {
  name?: string;
  colourHex?: string;
  isHidden?: boolean;
}
